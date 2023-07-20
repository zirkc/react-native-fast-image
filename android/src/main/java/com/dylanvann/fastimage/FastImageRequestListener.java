package com.dylanvann.fastimage;

import android.graphics.drawable.Drawable;

import com.bumptech.glide.load.DataSource;
import com.bumptech.glide.load.engine.GlideException;
import com.bumptech.glide.request.RequestListener;
import com.bumptech.glide.request.target.Target;

import java.util.List;

public class FastImageRequestListener implements RequestListener<Drawable> {
    private final String key;

    FastImageRequestListener(String key) {
        this.key = key;
    }

    @Override
    public boolean onLoadFailed(@androidx.annotation.Nullable GlideException e, Object model, Target<Drawable> target, boolean isFirstResource) {
        List<FastImageFetchStoreListener> listeners = FastImageFetchStore.getInstance().get(key);
        if (listeners != null) {
            for (FastImageFetchStoreListener listener : listeners) {
                listener.onLoadFailed();
            }
        }
        FastImageFetchStore.getInstance().remove(key);
        return false;
    }

    @Override
    public boolean onResourceReady(Drawable resource, Object model, Target<Drawable> target, DataSource dataSource, boolean isFirstResource) {
        List<FastImageFetchStoreListener> listeners = FastImageFetchStore.getInstance().get(key);
        if (listeners != null) {
            for (FastImageFetchStoreListener listener : listeners) {
                listener.onResourceReady(resource);
            }
            FastImageFetchStore.getInstance().remove(key);
        }
        return false;
    }
}
