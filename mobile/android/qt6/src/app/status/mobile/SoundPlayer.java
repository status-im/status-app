package app.status.mobile;

import android.media.AudioAttributes;
import android.media.SoundPool;
import android.util.Log;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Short UI sounds (notification, send, error) through SoundPool, so playing one does not
 * load QtMultimedia's FFmpeg backend. Called from StatusQ (mediabackend.cpp) with a local
 * file path; each file is decoded once and stays in the pool.
 */
public final class SoundPlayer {
    private static final String TAG = "SoundPlayer";
    private static SoundPool sPool;
    private static final Map<String, Integer> sIds = new HashMap<>();
    private static final Set<Integer> sLoaded = new HashSet<>();
    private static final Map<Integer, Float> sPending = new HashMap<>();
    private static final Map<Integer, Integer> sStreams = new HashMap<>();

    private SoundPlayer() {}

    private static SoundPool pool() {
        if (sPool == null) {
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
            sPool = new SoundPool.Builder().setMaxStreams(3).setAudioAttributes(attrs).build();
            sPool.setOnLoadCompleteListener((pool, id, status) -> {
                synchronized (SoundPlayer.class) {
                    Float volume = sPending.remove(id);
                    if (status != 0) {
                        Log.w(TAG, "load failed: " + status);
                        return;
                    }
                    sLoaded.add(id);
                    if (volume != null)
                        start(id, volume);
                }
            });
        }
        return sPool;
    }

    private static void start(int id, float volume) {
        int stream = sPool.play(id, volume, volume, 1, 0, 1f);
        if (stream == 0)
            Log.w(TAG, "play failed for sound " + id);
        else
            Log.d(TAG, "playing sound " + id);
        sStreams.put(id, stream);
    }

    public static synchronized void play(String path, float volume) {
        Integer id = sIds.get(path);
        if (id == null) {
            id = pool().load(path, 1);
            sIds.put(path, id);
        }
        if (sLoaded.contains(id))
            start(id, volume);
        else
            sPending.put(id, volume);
    }

    public static synchronized void stop(String path) {
        Integer id = sIds.get(path);
        if (id == null)
            return;
        sPending.remove(id);
        Integer stream = sStreams.remove(id);
        if (stream != null && stream != 0)
            sPool.stop(stream);
    }
}
