/*
 * Trireme for Deluge - A Deluge thin client for Android.
 * Copyright (C) 2018  Aashrava Holla
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package org.deluge.trireme;

import android.Manifest;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    static final String CHANNEL = "org.deluge.trireme";
    static final int REQUEST_CODE_FILE_PICKER = 0;
    static final int REQUEST_CODE_READ_PERMISSION = 1;

    MethodChannel.Result pickFileResult;

    String intentTorrentUrl;
    Uri intentTorrentFile;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (getIntent() != null) {
            saveIntentData();
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        listenForMethodChannelCalls(flutterEngine);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_CODE_FILE_PICKER) {
            if (resultCode == RESULT_CANCELED) {
                pickFileResult.error("CANCELLED", "User cancelled action", null);
            } else if (resultCode == RESULT_OK && data != null) {
                onFilePickerResult(data);
            } else {
                pickFileResult.error("ERROR", "Unknown error", null);
            }
            pickFileResult = null;
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        recreate();
    }

    void listenForMethodChannelCalls(FlutterEngine flutterEngine) {
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "pickFile":
                            pickFile(result);
                            break;
                        case "getOpenedUrl":
                            getOpenedUrl(result);
                            break;
                        case "getOpenedFile":
                            getOpenedFile(result);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });
    }

    void saveIntentData() {
        Intent intent = getIntent();
        if (intent.getData() == null) return;
        if (intent.getData().getScheme().equals(ContentResolver.SCHEME_CONTENT)
                || intent.getData().getScheme().equals(ContentResolver.SCHEME_FILE)) {
            intentTorrentFile = intent.getData();
        } else {
            intentTorrentUrl = intent.getDataString();
        }
    }

    void onFilePickerResult(Intent data) {
        Uri uri = data.getData();
        try {
            File f = copyFileToCacheDir(uri);
            pickFileResult.success(f.getAbsolutePath());
        } catch (IOException e) {
            pickFileResult.error("IMPORT_ERROR", "Error importing file", null);
        }
    }

    void pickFile(MethodChannel.Result result) {
        if (pickFileResult != null) {
            result.error("ALREADY_SHOWING", "Already showing file picker", null);
            return;
        }
        pickFileResult = result;
        showPicker();
    }

    void showPicker() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
        intent.setType("application/x-bittorrent");
        startActivityForResult(intent, REQUEST_CODE_FILE_PICKER);
    }

    void getOpenedUrl(MethodChannel.Result result) {
        if (intentTorrentUrl != null) {
            result.success(intentTorrentUrl);
        } else {
            result.error("NODATA", "No intent data", null);
        }
        intentTorrentUrl = null;
    }

    void getOpenedFile(MethodChannel.Result result) {
        if (intentTorrentFile != null) {
            if (!isReadPermissionGranted()) {
                requestReadPermission();
                return;
            }
            try {
                File f = copyFileToCacheDir(intentTorrentFile);
                String intentTorrentFilePath = f.getAbsolutePath();
                result.success(intentTorrentFilePath);
            } catch (IOException e) {
                result.error("ERROR", "Error opening file", null);
            }
        } else {
            result.error("NODATA", "No intent data", null);
        }
        intentTorrentFile = null;
    }

    File copyFileToCacheDir(Uri uri) throws IOException {
        //https://github.com/lucaslcode/import_file/blob/954a15be869abb8919199ccdfccf545efbd139ee/android/src/main/java/io/github/lucaslcode/importfile/ImportFilePlugin.java
        //copy file to cache dir so that it can be accessed by dart code
        String fileName = null;

        if (uri.getScheme().equals(ContentResolver.SCHEME_CONTENT)) {
            try (Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    fileName = cursor.getString(cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME));
                }
            }
        }
        if (fileName == null) {
            fileName = uri.getPath();
            int cut = fileName.lastIndexOf('/');
            if (cut != -1) {
                fileName = fileName.substring(cut + 1);
            }
        }
        File file = File.createTempFile(fileName, "", getCacheDir());
        try (InputStream input = getContentResolver().openInputStream(uri)) {
            try (OutputStream output = new FileOutputStream(file)) {
                byte[] buffer = new byte[4 * 1024];
                int read;
                while ((read = input.read(buffer)) != -1) {
                    output.write(buffer, 0, read);
                }
                output.flush();
            }
        }
        return file;
    }

    boolean isReadPermissionGranted() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED;
    }

    void requestReadPermission() {
        ActivityCompat.requestPermissions(this,
                new String[]{Manifest.permission.READ_EXTERNAL_STORAGE},
                REQUEST_CODE_READ_PERMISSION);
    }
}
