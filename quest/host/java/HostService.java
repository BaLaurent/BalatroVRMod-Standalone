package io.github.balaurent.balatrovr.host;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.IBinder;

/** Foreground service: stops Horizon OS from freezing the host while the immersive VR app has focus. */
public class HostService extends Service {
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel("host", "Balatro VR Host", NotificationManager.IMPORTANCE_LOW));
        Notification n = new Notification.Builder(this, "host")
                .setContentTitle("Balatro is running for Balatro in VR")
                .setSmallIcon(getApplicationInfo().icon)
                .setOngoing(true)
                .build();
        startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
