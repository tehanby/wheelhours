package com.wheelhours;

import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;
import com.wheelhours.location.LocationTrackingService;

public class MainActivity extends AppCompatActivity {

    private LocationTrackingService locationTrackingService;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        locationTrackingService = new LocationTrackingService(this);
    }

    @Override
    protected void onResume() {
        super.onResume();
        locationTrackingService.startLocationUpdates();
    }

    @Override
    protected void onPause() {
        super.onPause();
        locationTrackingService.stopLocationUpdates();
    }
}
