//! fix-migrations — repair the migration version marker of a status-go
//! sqlcipher database.
//!
//! A wallet database migrated by a newer build carries a version this build
//! does not know, and status-go refuses to open it. The schema changes behind
//! such migrations are additive, so the older build can use the file once the
//! marker is rolled back to the last version it knows.
//!
//!   fix-migrations list <migrations-dir>
//!   fix-migrations fix  <migrations-dir> <db-or-datadir> <password>
//!
//! `list` needs no password: it only reads the migration files of this checkout.
//! `fix` opens the database the way status-go does and rewrites the marker when
//! it is unknown to this build or left dirty; otherwise it changes nothing. The
//! database may be given as the `<keyUID>-wallet.db` file or as the profile's
//! data dir, when it holds a single profile.

use std::error::Error;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use aes::cipher::{KeyIvInit, StreamCipher};
use rusqlite::{Connection, OpenFlags};
use sha3::{Digest, Keccak256};

type Result<T> = std::result::Result<T, Box<dyn Error>>;

const MIGRATIONS_TABLE: &str = "status_go_schema_migrations";
/// status-go's ReducedKDFIterationsNumber: PBKDF2 rounds for legacy profiles.
const LEGACY_KDF_ITER: u32 = 3200;
/// status-go's V4CipherPageSize.
const CIPHER_PAGE_SIZE: u32 = 8192;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let outcome = match args.as_slice() {
        [mode, dir] if mode == "list" => list(Path::new(dir)),
        [mode, dir, db, password] if mode == "fix" => fix(Path::new(dir), Path::new(db), password),
        _ => Err("usage: fix-migrations list <migrations-dir> | fix <migrations-dir> <db> <password>".into()),
    };
    match outcome {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::FAILURE
        }
    }
}

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

/// Prints the migrations this checkout knows; the last one is what a build
/// from this checkout expects to find in the database.
fn list(migrations_dir: &Path) -> Result<()> {
    let known = known_migrations(migrations_dir)?;
    println!("migrations known to this checkout ({}):", migrations_dir.display());
    for (version, name) in &known {
        println!("  {version}  {name}");
    }
    let (latest, _) = known.last().ok_or("no migrations found")?;
    println!("this build expects version {latest}; older builds can roll back to any version above");
    Ok(())
}

/// Reads the marker and repairs it when this build could not open the database.
fn fix(migrations_dir: &Path, db_or_datadir: &Path, password: &str) -> Result<()> {
    let known = known_migrations(migrations_dir)?;
    let latest_known = known.last().map(|(v, _)| *v).ok_or("no migrations found")?;

    let db = &resolve_db_path(db_or_datadir)?;
    println!("database: {}", db.display());
    let (secret, kdf_iter) = resolve_secret(db, password)?;
    let conn = open_database(db, &secret, kdf_iter)?;
    let (version, dirty) = read_marker(&conn)?;
    println!("database marker: version {version}, dirty {dirty}");

    let is_known = known.iter().any(|(v, _)| *v == version);
    match plan(version, dirty, is_known, latest_known) {
        Action::Nothing => println!("nothing to do: this build knows version {version} and the marker is clean"),
        Action::ClearDirty => {
            write_marker(&conn, version)?;
            println!("cleared the dirty flag at version {version}");
        }
        Action::RollBack(to) => {
            write_marker(&conn, to)?;
            println!("rolled back {version} -> {to}, the newest version this build knows");
            println!("note: schema changes of the newer migrations stay in place; they are additive and harmless to this build");
        }
    }
    Ok(())
}

enum Action {
    Nothing,
    ClearDirty,
    RollBack(u64),
}

/// The whole repair policy in one place.
fn plan(version: u64, dirty: bool, is_known: bool, latest_known: u64) -> Action {
    if !is_known && version > latest_known {
        Action::RollBack(latest_known)
    } else if dirty {
        Action::ClearDirty
    } else {
        Action::Nothing
    }
}

/// Accepts the wallet DB itself, or a data dir / `data` folder holding exactly
/// one `<keyUID>-wallet.db`. With several profiles the caller has to pick one.
fn resolve_db_path(input: &Path) -> Result<PathBuf> {
    if input.is_file() {
        return Ok(input.to_path_buf());
    }
    if !input.is_dir() {
        return Err(format!("no such file or directory: {}", input.display()).into());
    }
    let data_dir = if input.join("data").is_dir() { input.join("data") } else { input.to_path_buf() };

    let mut wallets: Vec<PathBuf> = fs::read_dir(&data_dir)?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.file_name().and_then(|n| n.to_str()).map_or(false, |n| n.ends_with("-wallet.db")))
        .collect();
    wallets.sort();

    match wallets.as_slice() {
        [single] => Ok(single.clone()),
        [] => Err(format!("no *-wallet.db in {}", data_dir.display()).into()),
        many => {
            let listing = many.iter().map(|p| format!("  {}", p.display())).collect::<Vec<_>>().join("\n");
            Err(format!("{} holds several profiles, pass the wallet DB explicitly:\n{listing}", data_dir.display()).into())
        }
    }
}

// ---------------------------------------------------------------------------
// Migration files
// ---------------------------------------------------------------------------

/// `<version>_<name>.up.sql` files, sorted by version.
fn known_migrations(dir: &Path) -> Result<Vec<(u64, String)>> {
    let mut found = Vec::new();
    for entry in fs::read_dir(dir).map_err(|e| format!("{}: {e}", dir.display()))? {
        let name = entry?.file_name().to_string_lossy().into_owned();
        if let Some(prefix) = name.strip_suffix(".up.sql").and_then(|n| n.split('_').next()) {
            if let Ok(version) = prefix.parse::<u64>() {
                found.push((version, name));
            }
        }
    }
    found.sort();
    Ok(found)
}

// ---------------------------------------------------------------------------
// Key derivation, as status-go does it
// ---------------------------------------------------------------------------

/// A DEK profile keeps its database key wrapped in `<keyUID>-profile.kek` next
/// to the database; a legacy profile keys the database with the hashed
/// password directly.
fn resolve_secret(db: &Path, password: &str) -> Result<(String, u32)> {
    let hashed = hash_password(password);
    let envelope = envelope_path(db);
    if envelope.is_file() {
        let (dek, kdf_iter) = unwrap_dek(&envelope, &hashed)?;
        println!("profile: DEK ({})", envelope.display());
        Ok((dek, kdf_iter))
    } else {
        println!("profile: legacy (no {} found)", envelope.display());
        Ok((hashed, LEGACY_KDF_ITER))
    }
}

/// status-desktop never sends the plaintext: `"0x" + keccak256(password)`, lowercase.
fn hash_password(password: &str) -> String {
    format!("0x{}", hex::encode(Keccak256::digest(password.as_bytes())))
}

/// `<dir>/<keyUID>-wallet.db` → `<dir>/<keyUID>-profile.kek`
fn envelope_path(db: &Path) -> PathBuf {
    let name = db.file_name().and_then(|n| n.to_str()).unwrap_or("");
    let key_uid = name
        .strip_suffix("-wallet.db")
        .or_else(|| name.strip_suffix("-v4.db"))
        .or_else(|| name.strip_suffix(".db"))
        .unwrap_or(name);
    db.with_file_name(format!("{key_uid}-profile.kek"))
}

/// go-ethereum keystore V3 as written by status-go's envelope package:
/// scrypt → AES-128-CTR, keccak256 MAC. Returns the DEK as lowercase hex, which
/// is the sqlcipher passphrase, plus the PBKDF2 round count stored with it.
fn unwrap_dek(envelope: &Path, kek: &str) -> Result<(String, u32)> {
    let file: serde_json::Value = serde_json::from_slice(&fs::read(envelope)?)?;
    let crypto = &file["crypto"];
    if crypto["cipher"] != "aes-128-ctr" || crypto["kdf"] != "scrypt" {
        return Err("unsupported envelope: expected aes-128-ctr with scrypt".into());
    }
    let kdf_iter = file["dbKdfIterations"].as_u64().ok_or("envelope: dbKdfIterations missing")? as u32;

    let params = &crypto["kdfparams"];
    let salt = hex::decode(params["salt"].as_str().ok_or("envelope: salt missing")?)?;
    let n = params["n"].as_u64().ok_or("envelope: n missing")?;
    let r = params["r"].as_u64().ok_or("envelope: r missing")? as u32;
    let p = params["p"].as_u64().ok_or("envelope: p missing")? as u32;
    let dklen = params["dklen"].as_u64().ok_or("envelope: dklen missing")? as usize;

    let mut derived = vec![0u8; dklen];
    let scrypt_params = scrypt::Params::new(n.trailing_zeros() as u8, r, p, dklen)
        .map_err(|e| format!("envelope: bad scrypt params: {e:?}"))?;
    scrypt::scrypt(kek.as_bytes(), &salt, &scrypt_params, &mut derived)
        .map_err(|e| format!("envelope: scrypt failed: {e:?}"))?;

    let ciphertext = hex::decode(crypto["ciphertext"].as_str().ok_or("envelope: ciphertext missing")?)?;
    let mac = hex::decode(crypto["mac"].as_str().ok_or("envelope: mac missing")?)?;
    let expected_mac = Keccak256::new().chain_update(&derived[16..32]).chain_update(&ciphertext).finalize();
    if expected_mac.as_slice() != mac.as_slice() {
        return Err("wrong password for this profile (envelope MAC mismatch)".into());
    }

    let iv = hex::decode(crypto["cipherparams"]["iv"].as_str().ok_or("envelope: iv missing")?)?;
    let mut dek = ciphertext;
    ctr::Ctr128BE::<aes::Aes128>::new(derived[..16].into(), iv.as_slice().into()).apply_keystream(&mut dek);
    Ok((hex::encode(dek), kdf_iter))
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// The PRAGMA sequence of status-go's `openDB`; a wrong key surfaces on the
/// first read as "file is not a database".
fn open_database(path: &Path, secret: &str, kdf_iter: u32) -> Result<Connection> {
    if !path.is_file() {
        return Err(format!("database not found: {}", path.display()).into());
    }
    let conn = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_WRITE)?;
    conn.pragma_update(None, "key", secret)?;
    conn.pragma_update(None, "cipher_page_size", CIPHER_PAGE_SIZE)?;
    conn.execute_batch("PRAGMA cipher_hmac_algorithm = HMAC_SHA1; PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA1;")?;
    conn.pragma_update(None, "kdf_iter", kdf_iter)?;
    conn.pragma_update(None, "busy_timeout", 60_000)?;
    conn.query_row("SELECT count(*) FROM sqlite_master", [], |_| Ok(()))
        .map_err(|_| "could not decrypt the database: wrong password?")?;
    Ok(conn)
}

/// The single row of the migrations table. status-go stores `dirty` as the
/// strings 'true'/'false'.
fn read_marker(conn: &Connection) -> Result<(u64, bool)> {
    let (version, dirty): (i64, String) = conn
        .query_row(&format!("SELECT version, CAST(dirty AS TEXT) FROM {MIGRATIONS_TABLE} LIMIT 1"), [], |row| {
            Ok((row.get(0)?, row.get(1)?))
        })
        .map_err(|e| format!("{MIGRATIONS_TABLE}: {e}"))?;
    Ok((version as u64, matches!(dirty.as_str(), "true" | "1")))
}

/// Exactly what the migrate library's SetVersion does: DELETE, then INSERT one row.
fn write_marker(conn: &Connection, version: u64) -> Result<()> {
    let tx = conn.unchecked_transaction()?;
    tx.execute(&format!("DELETE FROM {MIGRATIONS_TABLE}"), [])?;
    tx.execute(&format!("INSERT INTO {MIGRATIONS_TABLE} (version, dirty) VALUES (?1, 'false')"), [version as i64])?;
    tx.commit()?;
    Ok(())
}
