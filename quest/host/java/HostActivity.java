package io.github.balaurent.balatrovr.host;

import android.content.Intent;
import android.os.Bundle;

/** LÖVE's game activity, plus a foreground service that keeps Balatro alive behind the VR app. */
public class HostActivity extends org.love2d.android.GameActivity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        // The VR client is NOT launched here: the SDL game thread only starts once this activity is
        // resumed with a surface, so the bridge launches the client from Balatro's first frames.
        startForegroundService(new Intent(this, HostService.class));
    }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        // tapping the host icon while Balatro already runs brings the VR client back
        if (Intent.ACTION_MAIN.equals(i.getAction())) LaunchClientActivity.launchClient(this);
    }

    @Override
    protected void onDestroy() {
        stopService(new Intent(this, HostService.class));
        super.onDestroy();
        // LÖVE cannot start its main() twice in one process: when Balatro quits (the VR app is gone),
        // end the process so the next launch from the library starts clean
        if (isFinishing()) android.os.Process.killProcess(android.os.Process.myPid());
    }
}
