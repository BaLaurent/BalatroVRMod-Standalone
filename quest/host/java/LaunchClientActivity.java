package io.github.balaurent.balatrovr.host;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

/** Target of balatrovr-host://launch-client (fired by the bridge): starts the Balatro in VR app. */
public class LaunchClientActivity extends Activity {
    static final String CLIENT = "io.github.balaurent.balatroinvr";

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        launchClient(this);
        finish();
    }

    static void launchClient(Context c) {
        Intent i = c.getPackageManager().getLaunchIntentForPackage(CLIENT);
        if (i == null) {
            Log.w("BalatroVRHost", "Balatro in VR (" + CLIENT + ") is not installed");
            Toast.makeText(c, "Install Balatro in VR (the VR app) first", Toast.LENGTH_LONG).show();
            return;
        }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        c.startActivity(i);
        Log.i("BalatroVRHost", "launched " + CLIENT);
    }
}
