package com.squeezo.app;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.provider.OpenableColumns;

import androidx.activity.result.ActivityResult;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.PluginMethod;

import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.effect.Presentation;
import androidx.media3.transformer.DefaultEncoderFactory;
import androidx.media3.transformer.EditedMediaItem;
import androidx.media3.transformer.Effects;
import androidx.media3.transformer.ExportException;
import androidx.media3.transformer.ExportResult;
import androidx.media3.transformer.ProgressHolder;
import androidx.media3.transformer.Transformer;
import androidx.media3.transformer.VideoEncoderSettings;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@UnstableApi
@CapacitorPlugin(name = "SqueezoVideoCompressor")
public class SqueezoVideoCompressorPlugin extends Plugin {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Transformer activeTransformer;
    private Runnable progressRunnable;

    @PluginMethod
    public void pickVideos(PluginCall call) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("video/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        startActivityForResult(call, intent, "pickVideosResult");
    }

    @ActivityCallback
    private void pickVideosResult(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
            call.reject("Picker cancelled");
            return;
        }
        Intent data = result.getData();
        JSArray files = new JSArray();
        try {
            if (data.getClipData() != null) {
                for (int i = 0; i < data.getClipData().getItemCount(); i++) {
                    Uri uri = data.getClipData().getItemAt(i).getUri();
                    persistPermission(uri, data.getFlags());
                    files.put(metadata(uri));
                }
            } else if (data.getData() != null) {
                Uri uri = data.getData();
                persistPermission(uri, data.getFlags());
                files.put(metadata(uri));
            }
            JSObject ret = new JSObject();
            ret.put("files", files);
            call.resolve(ret);
        } catch (Exception e) {
            call.reject("Unable to read selected video: " + e.getMessage());
        }
    }

    private void persistPermission(Uri uri, int flags) {
        try {
            getContext().getContentResolver().takePersistableUriPermission(
                uri, flags & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            );
        } catch (Exception ignored) {}
    }

    private JSObject metadata(Uri uri) {
        JSObject o = new JSObject();
        o.put("path", uri.toString());
        o.put("mimeType", getContext().getContentResolver().getType(uri));
        o.put("name", uri.getLastPathSegment() == null ? "video.mp4" : uri.getLastPathSegment());
        o.put("size", 0);
        Cursor c = null;
        try {
            c = getContext().getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}, null, null, null);
            if (c != null && c.moveToFirst()) {
                int nameIndex = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                int sizeIndex = c.getColumnIndex(OpenableColumns.SIZE);
                if (nameIndex >= 0) o.put("name", c.getString(nameIndex));
                if (sizeIndex >= 0 && !c.isNull(sizeIndex)) o.put("size", c.getLong(sizeIndex));
            }
        } catch (Exception ignored) {} finally {
            if (c != null) c.close();
        }
        return o;
    }

    @PluginMethod
    public void compress(PluginCall call) {
        String path = call.getString("path");
        if (path == null || path.isEmpty()) {
            call.reject("Video path is missing");
            return;
        }
        int bitrate = Math.max(300_000, call.getInt("bitrate", 3_500_000));
        int maxHeight = call.getInt("maxHeight", 0);
        int fps = call.getInt("fps", 0);

        try {
            Uri inputUri = Uri.parse(path);
            File dir = new File(getContext().getExternalFilesDir(Environment.DIRECTORY_MOVIES), "Squeezo");
            if (!dir.exists() && !dir.mkdirs()) throw new Exception("Cannot create output directory");
            String base = safeName(getNameFromUri(inputUri));
            File output = new File(dir, base + "_squeezo.mp4");
            if (output.exists()) output.delete();

            MediaItem mediaItem = MediaItem.fromUri(inputUri);
            EditedMediaItem.Builder editedBuilder = new EditedMediaItem.Builder(mediaItem);
            List<androidx.media3.common.Effect> videoEffects = new ArrayList<>();
            if (maxHeight > 0) videoEffects.add(Presentation.createForHeight(maxHeight));
            if (!videoEffects.isEmpty()) {
                editedBuilder.setEffects(new Effects(Collections.emptyList(), videoEffects));
            }
            if (fps > 0) editedBuilder.setFrameRate(fps);
            EditedMediaItem edited = editedBuilder.build();

            VideoEncoderSettings settings = new VideoEncoderSettings.Builder()
                .setBitrate(bitrate)
                .build();
            DefaultEncoderFactory encoderFactory = new DefaultEncoderFactory.Builder(getContext())
                .setRequestedVideoEncoderSettings(settings)
                .build();

            final String outputPath = output.getAbsolutePath();
            activeTransformer = new Transformer.Builder(getContext())
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .addListener(new Transformer.Listener() {
                    @Override
                    public void onCompleted(androidx.media3.transformer.Composition composition, ExportResult exportResult) {
                        stopProgress();
                        try {
                            JSObject saved = publishOutput(output, base + "_squeezo.mp4");
                            call.resolve(saved);
                        } catch (Exception e) {
                            call.reject("Video was encoded but could not be saved: " + e.getMessage());
                        } finally {
                            activeTransformer = null;
                        }
                    }

                    @Override
                    public void onError(androidx.media3.transformer.Composition composition, ExportResult exportResult, ExportException exception) {
                        stopProgress();
                        activeTransformer = null;
                        String message = exception.getMessage() == null ? "Native video compression failed" : exception.getMessage();
                        call.reject(message);
                    }
                })
                .build();

            startProgress();
            activeTransformer.start(edited, outputPath);
        } catch (Exception e) {
            stopProgress();
            call.reject("Native video compression failed: " + e.getMessage());
        }
    }

    private void startProgress() {
        stopProgress();
        progressRunnable = new Runnable() {
            @Override public void run() {
                if (activeTransformer == null) return;
                try {
                    ProgressHolder holder = new ProgressHolder();
                    int state = activeTransformer.getProgress(holder);
                    if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                        JSObject data = new JSObject();
                        data.put("value", holder.progress);
                        notifyListeners("progress", data);
                    }
                } catch (Exception ignored) {}
                handler.postDelayed(this, 400);
            }
        };
        handler.post(progressRunnable);
    }

    private void stopProgress() {
        if (progressRunnable != null) handler.removeCallbacks(progressRunnable);
        progressRunnable = null;
    }

    private JSObject publishOutput(File source, String displayName) throws Exception {
        JSObject ret = new JSObject();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentResolver resolver = getContext().getContentResolver();
            ContentValues values = new ContentValues();
            values.put(MediaStore.Video.Media.DISPLAY_NAME, displayName);
            values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
            values.put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Squeezo");
            values.put(MediaStore.Video.Media.IS_PENDING, 1);
            Uri uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new Exception("MediaStore insert failed");
            try (InputStream in = new FileInputStream(source); OutputStream out = resolver.openOutputStream(uri)) {
                if (out == null) throw new Exception("Cannot open destination");
                byte[] buffer = new byte[1024 * 1024];
                int n;
                while ((n = in.read(buffer)) != -1) out.write(buffer, 0, n);
            }
            ContentValues done = new ContentValues();
            done.put(MediaStore.Video.Media.IS_PENDING, 0);
            resolver.update(uri, done, null, null);
            ret.put("uri", uri.toString());
        } else {
            ret.put("uri", androidx.core.content.FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", source).toString());
        }
        ret.put("path", source.getAbsolutePath());
        ret.put("name", displayName);
        ret.put("size", source.length());
        return ret;
    }

    @PluginMethod
    public void share(PluginCall call) {
        String uriString = call.getString("uri");
        String mime = call.getString("mimeType", "video/mp4");
        String name = call.getString("name", "Squeezo.mp4");
        if (uriString == null || uriString.isEmpty()) { call.reject("File URI is missing"); return; }
        try {
            Uri uri = Uri.parse(uriString);
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType(mime);
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.putExtra(Intent.EXTRA_TITLE, name);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(intent, "Share with");
            getActivity().startActivity(chooser);
            call.resolve();
        } catch (Exception e) { call.reject("Unable to share file: " + e.getMessage()); }
    }

    private String getNameFromUri(Uri uri) {
        Cursor c = null;
        try {
            c = getContext().getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null);
            if (c != null && c.moveToFirst()) {
                int i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (i >= 0) return c.getString(i);
            }
        } catch (Exception ignored) {} finally { if (c != null) c.close(); }
        return "video.mp4";
    }

    private String safeName(String name) {
        String base = name == null ? "video" : name.replaceAll("[^a-zA-Z0-9._-]", "_");
        base = base.replaceFirst("\\.[^.]+$", "");
        if (base.isEmpty()) base = "video";
        return base;
    }
}
