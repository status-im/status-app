package app.status.mobile;

import android.content.Context;
import android.system.Os;
import android.util.Log;

import org.qtproject.qt.android.bindings.QtApplication;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;

/**
 * Application class for both processes. In profiling builds it applies
 * {@code KEY=VALUE} lines from {@code <external files dir>/status-env.txt} to the
 * process environment before any native library is loaded, so Qt (QSG_*, QT_LOGGING_RULES) and
 * STATUS_RUNTIME_* pick them up per launch. The Go runtime does not: it keeps the environment the
 * loader passed at process start.
 */
public class StatusApplication extends QtApplication {
    private static final String TAG = "StatusApplication";
    static final String ENV_FILE = "status-env.txt";

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        if (BuildFlags.PROFILING) applyEnvFile(base);
    }

    private static void applyEnvFile(Context context) {
        final File dir = context.getExternalFilesDir(null);
        if (dir == null) return;
        final File file = new File(dir, ENV_FILE);
        if (!file.isFile()) return;
        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                final int eq = line.indexOf('=');
                if (eq <= 0) continue;
                final String key = line.substring(0, eq).trim();
                final String value = line.substring(eq + 1).trim();
                Os.setenv(key, value, true);
                Log.i(TAG, "env " + key + "=" + value);
            }
        } catch (Exception e) {
            Log.w(TAG, "failed to apply " + file, e);
        }
    }
}
