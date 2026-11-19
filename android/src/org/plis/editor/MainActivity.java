// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 команда S.T.A.R.K.
package org.plis.editor;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import java.io.OutputStream;

/**
 * Оболочка P.L.I.S.: показывает редактор (web/index.html) во встроенном WebView.
 * Сторонних библиотек нет — только то, что входит в сам Android.
 * Разрешения на интернет приложение не запрашивает, поэтому сети у него нет вообще.
 */
public class MainActivity extends Activity {
    private static final int REQ_SAVE = 1;
    private static final int REQ_OPEN = 2;
    private static final String APP_URL = "file:///android_asset/index.html";
    private static final String ASSET_PREFIX = "file:///android_asset/";

    private WebView web;
    private ValueCallback<Uri[]> openCallback;
    private byte[] pendingSave;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Window w = getWindow();
        w.setStatusBarColor(0xFF14233A);
        w.setNavigationBarColor(0xFF15222F);

        web = new WebView(this);
        web.setBackgroundColor(0xFF0F1A26);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);      // здесь хранится автосохранение схемы
        s.setAllowFileAccess(false);       // файлы из assets это не затрагивает
        s.setAllowContentAccess(false);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setTextZoom(100);

        web.addJavascriptInterface(new Bridge(), "PlisAndroid");

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                // ничего, кроме самого редактора, не открываем
                return !request.getUrl().toString().startsWith(ASSET_PREFIX);
            }
        });

        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                                             FileChooserParams params) {
                if (openCallback != null) {
                    openCallback.onReceiveValue(null);
                }
                openCallback = callback;
                Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
                pick.addCategory(Intent.CATEGORY_OPENABLE);
                pick.setType("*/*");
                try {
                    startActivityForResult(Intent.createChooser(pick, "Открыть схему"), REQ_OPEN);
                } catch (ActivityNotFoundException e) {
                    openCallback = null;
                    callback.onReceiveValue(null);
                    return false;
                }
                return true;
            }
        });

        if (state != null) {
            web.restoreState(state);
        } else {
            web.loadUrl(APP_URL);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    /** Кнопка «Назад»: сначала закрываем окошко или список, и только потом выходим. */
    @Override
    public void onBackPressed() {
        web.evaluateJavascript("window.plisBack?window.plisBack():false", new ValueCallback<String>() {
            @Override
            public void onReceiveValue(String handled) {
                if (!"true".equals(handled)) {
                    finish();
                }
            }
        });
    }

    /** Мост для JavaScript: сохранение файла через системное окно «Сохранить как». */
    public class Bridge {
        @JavascriptInterface
        public void saveFile(final String name, final String mime, String base64) {
            final byte[] data;
            try {
                data = Base64.decode(base64, Base64.DEFAULT);
            } catch (IllegalArgumentException e) {
                toast("Не удалось подготовить файл");
                return;
            }
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    startSave(name, mime, data);
                }
            });
        }
    }

    private void startSave(String name, String mime, byte[] data) {
        pendingSave = data;
        Intent save = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        save.addCategory(Intent.CATEGORY_OPENABLE);
        save.setType(mime == null || mime.length() == 0 ? "application/octet-stream" : mime);
        save.putExtra(Intent.EXTRA_TITLE, name);
        try {
            startActivityForResult(save, REQ_SAVE);
        } catch (ActivityNotFoundException e) {
            pendingSave = null;
            toast("На телефоне нет приложения для сохранения файлов");
        }
    }

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        if (request == REQ_SAVE) {
            byte[] bytes = pendingSave;
            pendingSave = null;
            if (result == RESULT_OK && data != null && data.getData() != null && bytes != null) {
                try {
                    OutputStream out = getContentResolver().openOutputStream(data.getData());
                    try {
                        out.write(bytes);
                    } finally {
                        out.close();
                    }
                    toast("Файл сохранён");
                } catch (Exception e) {
                    toast("Не удалось сохранить файл");
                }
            }
        } else if (request == REQ_OPEN) {
            Uri[] picked = null;
            if (result == RESULT_OK && data != null && data.getData() != null) {
                picked = new Uri[] { data.getData() };
            }
            if (openCallback != null) {
                openCallback.onReceiveValue(picked);
                openCallback = null;
            }
        } else {
            super.onActivityResult(request, result, data);
        }
    }

    private void toast(final String text) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(MainActivity.this, text, Toast.LENGTH_SHORT).show();
            }
        });
    }
}
