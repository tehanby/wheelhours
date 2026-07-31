package com.example.wheelhours;

import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

public class OnboardingActivity extends AppCompatActivity {

    private EditText supervisorNameEditText, vehicleNameEditText;
    private Button submitButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_onboarding);

        supervisorNameEditText = findViewById(R.id.supervisor_name_edit_text);
        vehicleNameEditText = findViewById(R.id.vehicle_name_edit_text);
        submitButton = findViewById(R.id.submit_button);

        submitButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String supervisorName = supervisorNameEditText.getText().toString();
                String vehicleName = vehicleNameEditText.getText().toString();

                if (supervisorName.isEmpty() || vehicleName.isEmpty()) {
                    Toast.makeText(OnboardingActivity.this, "Please fill in all fields", Toast.LENGTH_SHORT).show();
                } else {
                    saveSupervisorAndVehicle(supervisorName, vehicleName);
                    finish(); // Return to MainActivity
                }
            }
        });
    }

    private void saveSupervisorAndVehicle(String supervisorName, String vehicleName) {
        SharedPreferences settings = getSharedPreferences("UserPrefs", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = settings.edit();
        editor.putString("supervisorName", supervisorName);
        editor.putString("vehicleName", vehicleName);
        editor.apply();

        Toast.makeText(this, "Supervisor and Vehicle added successfully!", Toast.LENGTH_SHORT).show();
    }
}
