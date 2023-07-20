package com.dylanvann.fastimage;

import java.util.concurrent.ConcurrentHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

public class FastImageFetchStore {
    private static FastImageFetchStore instance;
    private Map<String, List<FastImageFetchStoreListener>> fetchListeners;

    private FastImageFetchStore() {
        fetchListeners = new ConcurrentHashMap<>();
    }

    public static FastImageFetchStore getInstance() {
        if (instance == null) {
            instance = new FastImageFetchStore();
        }
        return instance;
    }

    public void add(String url, FastImageFetchStoreListener callback) {
        List<FastImageFetchStoreListener> callbacks = fetchListeners.get(url);
        if (callbacks == null) {
            callbacks = new CopyOnWriteArrayList<>();
            fetchListeners.put(url, callbacks);
        }
        callbacks.add(callback);
    }

    public void remove(String url) {
        fetchListeners.remove(url);
    }

    public List<FastImageFetchStoreListener> get(String url) {
        return fetchListeners.get(url);
    }

    public void clear() {
        fetchListeners.clear();
    }
}
