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

import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    static final String CHANNEL = "org.deluge.trireme";
    static final int REQUEST_CODE_FILE_PICKER = 0;

    MethodChannel.Result pickFileResult;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        GeneratedPluginRegistrant.registerWith(this);
        new MethodChannel(getFlutterView(), CHANNEL).setMethodCallHandler((call, result) -> {
            if (call.method.equals("pickFile")) {
                if (pickFileResult != null) {
                    result.error("ALREADY_SHOWING","Already showing file picker", null);
                    return;
                }
                pickFileResult = result;
                pickFile();
            } else {
                result.notImplemented();
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 0) {
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pickFile();
            }
        }
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

    void pickFile() {
        showPicker();
    }

    void showPicker() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
        intent.setType("application/x-bittorrent");
        startActivityForResult(intent, REQUEST_CODE_FILE_PICKER);
    }

    void onFilePickerResult(Intent data) {
        //https://github.com/lucaslcode/import_file/blob/954a15be869abb8919199ccdfccf545efbd139ee/android/src/main/java/io/github/lucaslcode/importfile/ImportFilePlugin.java
        //copy file to cache dir so that it can be accessed by dart code

        Uri uri = data.getData();
        String fileName = null;

        if (uri.getScheme().equals("content")) {
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
        try {
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
            pickFileResult.success(file.getAbsolutePath());
        } catch (IOException e){
            pickFileResult.error("IMPORT_ERROR", "Error importing file", null);
        }
    }
}
