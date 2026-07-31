# Performance Optimizations Migration

from django.db import migrations

class Migration(migrations.Migration):

    dependencies = [
        ('your_app_name', '001_final_schema_changes'),
    ]

    operations = [
        # Add performance optimization changes here
        migrations.AddIndex(
            model_name='employee',
            index=models.Index(fields=['date_joined']),
        ),
        migrations.RunSQL('CREATE INDEX idx_employee_department ON your_app_name_employee(department_id);'),
    ]
