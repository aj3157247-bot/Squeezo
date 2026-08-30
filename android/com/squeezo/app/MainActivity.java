package com.squeezo.app;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(android.os.Bundle savedInstanceState) {
        registerPlugin(SqueezoVideoCompressorPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
