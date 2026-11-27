import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys

SEVERITIES = {"Likely bug": 0, "Possible issue": 1, "Minor": 2}
INLINE_FOOTER = "<sub>AI review (trial). It can be wrong. React 👍 or 👎 to rate this comment.</sub>"
CREDENTIAL = re.compile(
    r"gh[pousr]_[A-Za-z0-9]{20}|github_pat_|sk-ant-|x-access-token|eC1hY2Nlc3MtdG9rZW4"
    r"|\bauthorization[\"']?\s*:\s*[\"']?(?:bearer|basic)\s+\S",
    re.IGNORECASE,
)
SHA = re.compile(r"[0-9a-f]{40}")
SIZE_LIMIT = 128_000


class Withheld(ValueError):
    pass


def validate(review):
    if not isinstance(review, dict) or review.keys() - {"verdict", "tests", "findings"}:
        raise ValueError("Invalid review")
    if not isinstance(review.get("verdict"), str):
        raise ValueError("Invalid verdict")
    findings = [] if review.get("findings") is None else review["findings"]
    tests = [] if review.get("tests") is None else review["tests"]
    if not isinstance(findings, list) or not isinstance(tests, list):
        raise ValueError("Invalid lists")
    for finding in findings:
        if (not isinstance(finding, dict)
                or set(finding) != {"severity", "location", "title", "detail", "inline"}
                or not all(isinstance(finding[k], str) for k in ("severity", "location", "title", "detail"))
                or finding["severity"] not in SEVERITIES or type(finding["inline"]) is not bool):
            raise ValueError("Invalid finding")
    if not all(isinstance(test, str) for test in tests):
        raise ValueError("Invalid tests")
    text = [review["verdict"], *tests]
    text.extend(f[key] for f in findings for key in ("location", "title", "detail"))
    if any(CREDENTIAL.search(value) for value in text):
        raise Withheld("Credential-like output")
    return {"verdict": review["verdict"],
            "findings": sorted(findings, key=lambda f: SEVERITIES[f["severity"]])[:5],
            "tests": tests[:3]}


def clean(value, limit):
    value = re.sub(r"[\x00-\x1f\x7f-\x9f]", " ", value[:limit])
    value = re.sub(r"(?i)www\.", lambda m: m[0][:-1] + "\u200b.", value)
    value = value.replace("://", ":/\u200b/").replace("@", "@\u200b").replace("#", "#\u200b")
    value = html.escape(value, quote=False)
    return re.sub(r"([\\\x60*_{}\[\]()!|~$])", r"\\\1", value)


def read_json(path, limit):
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Review data exceeds limit")
    return json.loads(data)


def result_file():
    return Path(os.environ["RUNNER_TEMP"]) / "ai-review-result" / "review.json"


def prepare():
    sha = os.environ["HEAD_SHA"]
    if not SHA.fullmatch(sha):
        return 1
    result = {}
    review = None
    status = "failed"
    try:
        history = read_json(Path(os.environ["EXEC"]), 32_000_000)
        if isinstance(history, list):
            result = next((r for r in reversed(history) if isinstance(r, dict)
                           and r.get("type") == "result"), {})
        if result.get("subtype") == "success" and not result.get("is_error"):
            raw = result.get("structured_output")
            if isinstance(raw, str):
                raw = json.loads(raw)
            if len(json.dumps(raw)) <= SIZE_LIMIT:
                review = validate(raw)
                status = "ok"
    except Withheld:
        status = "withheld"
    except (ValueError, OSError, RecursionError):
        pass

    def number(key):
        value = result.get(key)
        return value if type(value) in (int, float) and 0 <= value < 1_000_000 else None

    model = os.environ["MODEL"]
    if not re.fullmatch(r"[\w.-]{1,80}", model):
        model = "configured"
    cost, turns = number("total_cost_usd"), number("num_turns")
    cost_text = "unknown" if cost is None else f"${cost:.2f}"
    turns_text = "unknown" if turns is None else str(int(turns))
    count = len(review["findings"]) if review else 0
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(f"ai-review model: {model}; turns: {turns_text}; cost: {cost_text}; "
                      f"findings: {count}; status: {status}\n")

    path = result_file()
    data = json.dumps({"head": sha, "status": status, "review": review}).encode()
    if os.environ["LIVE"] == "true" or (os.environ["PRIVATE"] == "true" and review is not None):
        path.parent.mkdir()
        path.write_bytes(data)
    elif review is not None and (certificate := os.environ.get("DRY_RUN_CERTIFICATE")):
        cert = Path(os.environ["RUNNER_TEMP"]) / "ai-review-recipient.pem"
        cert.write_text(certificate, encoding="utf-8")
        sealed = subprocess.run(
            ["openssl", "cms", "-encrypt", "-binary", "-aes256", "-outform", "DER", str(cert)],
            input=data, capture_output=True, check=False,
        )
        if sealed.returncode != 0:
            print("Could not encrypt the dry-run artifact.", file=sys.stderr)
            return 1
        path.parent.mkdir()
        path.with_suffix(".cms").write_bytes(sealed.stdout)
    return 0


def gh(*args, data=None):
    return subprocess.run(["gh", "api", *args], check=True, text=True, capture_output=True,
                          input=json.dumps(data) if data is not None else None).stdout


def added_lines(patch):
    line = None
    for row in patch.split("\n"):
        hunk = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", row)
        if hunk:
            line = int(hunk[1])
        elif line is not None and row.startswith(("+", " ")):
            if row[0] == "+":
                yield line
            line += 1


def render(review, posted):
    body = [f"**{clean(review['verdict'], 400)}**", ""]
    main = [(i, f) for i, f in enumerate(review["findings"]) if f["severity"] != "Minor"]
    minor = [f for f in review["findings"] if f["severity"] == "Minor"]
    if main:
        body.append("### Findings")
        for i, f in main:
            detail = " _(inline comment)_" if i in posted else f"<br>{clean(f['detail'], 800)}"
            body.append(f"- **{f['severity']}:** {clean(f['location'], 200)} {clean(f['title'], 200)}{detail}")
        body.append("")
    if minor:
        body.extend([f"<details><summary>Minor ({len(minor)})</summary>", ""])
        body.extend(f"- {clean(f['location'], 200)} {clean(f['title'], 200)} {clean(f['detail'], 800)}"
                    for f in minor)
        body.extend(["", "</details>", ""])
    if review["tests"]:
        body.extend(["### Suggested tests", *(f"- {clean(t, 300)}" for t in review["tests"]), ""])
    return body


def inline_review(pr_url, sha, review):
    candidates = [(i, f) for i, f in enumerate(review["findings"]) if f["inline"] and f["severity"] != "Minor"]
    if not candidates or gh(pr_url, "--jq", ".head.sha").strip() != sha:
        return set()
    pages = json.loads(gh(f"{pr_url}/files?per_page=100", "--paginate", "--slurp"))
    files = {f["filename"]: set(added_lines(f.get("patch") or "")) for page in pages for f in page}
    comments = []
    posted = {}
    for i, f in candidates:
        location = f["location"]
        path, _, number = location.rpartition(":")
        if not re.fullmatch(r"[1-9][0-9]{0,8}", number) or int(number) not in files.get(path, ()):
            continue
        if location in posted:
            continue
        comments.append({"path": path, "line": int(number), "side": "RIGHT",
                         "body": (f"**{f['severity']}:** {clean(f['title'], 200)}\n\n"
                                  f"{clean(f['detail'], 800)}\n\n{INLINE_FOOTER}")})
        posted[location] = i
    if not comments:
        return set()
    pages = json.loads(gh(f"{pr_url}/comments?per_page=100", "--paginate", "--slurp"))
    existing = {(c["path"], c.get("original_line"), c["body"]) for page in pages for c in page
                if (c.get("user") or {}).get("login") == "github-actions[bot]" and c["original_commit_id"] == sha}
    new = [c for c in comments if (c["path"], c["line"], c["body"]) not in existing]
    if gh(pr_url, "--jq", ".head.sha").strip() != sha:
        return set()
    if new:
        gh("-X", "POST", f"{pr_url}/reviews", "--input", "-",
           data={"event": "COMMENT", "commit_id": sha, "comments": new})
    return set(posted.values())


def post():
    if os.environ["ASSOC"] not in {"OWNER", "MEMBER", "COLLABORATOR"}:
        return 1
    sha = os.environ["HEAD_SHA"]
    if not SHA.fullmatch(sha):
        return 1
    status, review = "failed", None
    try:
        envelope = read_json(result_file(), SIZE_LIMIT * 2)
        if (not isinstance(envelope, dict) or set(envelope) != {"head", "status", "review"}
                or envelope["head"] != sha):
            raise ValueError("Review does not match the event")
        if envelope["status"] == "ok":
            review = validate(envelope["review"])
            status = "ok"
        elif envelope["status"] == "withheld":
            status = "withheld"
    except Withheld:
        status = "withheld"
    except (ValueError, OSError, RecursionError):
        pass

    repo, pr = os.environ["REPO"], os.environ["PR"]
    pr_url = f"repos/{repo}/pulls/{pr}"
    body = ["<!-- ai-review -->", "## AI review (trial)", "", f"Commit: `{sha}`", ""]
    if review is not None:
        try:
            posted = inline_review(pr_url, sha, review)
        except (ValueError, subprocess.CalledProcessError):
            posted = set()
        body.extend(render(review, posted))
    elif status == "withheld":
        body.append("**The review was withheld: its output looked like it contained a credential.**")
    else:
        body.extend(["**The review could not finish on this PR. Add the \x60ai-review\x60 label to try again.**",
                     "", f"[Run log]({os.environ['RUN_URL']})"])
    body.extend(["---", f"<sub>AI review (trial) by {clean(os.environ['MODEL'], 80)}. "
                 "It can be wrong: check each point before you act. React 👍 or 👎 to rate it. "
                 "Add the ai-review label to run it again.</sub>"])

    url = f"repos/{repo}/issues/{pr}/comments"
    ids = gh(url, "--paginate", "--jq",
             '.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("<!-- ai-review -->"))) | .id')
    keep = ids.splitlines()[0] if ids.strip() else ""
    if gh(pr_url, "--jq", ".head.sha").strip() != sha:
        return 0
    if keep:
        gh("-X", "PATCH", f"repos/{repo}/issues/comments/{keep}", "--input", "-",
           data={"body": "\n".join(body)})
    else:
        gh("-X", "POST", url, "--input", "-", data={"body": "\n".join(body)})
    return int(status != "ok")


if __name__ == "__main__":
    try:
        sys.exit({"prepare": prepare, "post": post}[sys.argv[1]]())
    except (OSError, subprocess.CalledProcessError):
        print("Could not complete the review step.", file=sys.stderr)
        sys.exit(1)
