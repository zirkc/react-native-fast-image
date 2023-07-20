package com.dylanvann.fastimage;

import android.graphics.drawable.Drawable;

import com.bumptech.glide.request.target.Target;

public interface FastImageFetchStoreListener {
	void onLoadFailed();
	void onResourceReady(Drawable resource);
}
