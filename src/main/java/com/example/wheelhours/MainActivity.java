package com.example.wheelhours;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import androidx.appcompat.app.AppCompatActivity;
import android.os.Bundle;

public class MainActivity extends AppCompatActivity {

    private static final String PREFS_NAME = "MyPrefsFile";
    private static final String FIRST_LAUNCH_KEY = "firstLaunch";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        SharedPreferences settings = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        boolean firstLaunch = settings.getBoolean(FIRST_LAUNCH_KEY, true);

        if (firstLaunch) {
            Intent onboardingIntent = new Intent(MainActivity.this, OnboardingActivity.class);
            startActivity(onboardingIntent);

            SharedPreferences.Editor editor = settings.edit();
            editor.putBoolean(FIRST_LAUNCH_KEY, false);
            editor.apply();
        }
    }
}
