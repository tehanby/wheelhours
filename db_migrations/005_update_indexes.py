# Update Indexes Migration

from django.db import migrations, connection

class Migration(migrations.Migration):

    dependencies = [
        ('your_app_name', '004_finalize_data_cleaning'),
    ]

    operations = [
        # Add index update changes here
        migrations.RunSQL('DROP INDEX idx_employee_department;'),
        migrations.AddIndex(
            model_name='employee',
            index=models.Index(fields=['department_id']),
        ),
    ]
