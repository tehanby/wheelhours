# Finalize Data Cleaning Migration

from django.db import migrations, connection

class Migration(migrations.Migration):

    dependencies = [
        ('your_app_name', '003_compliance_check_trigger'),
    ]

    operations = [
        # Add data cleaning changes here
        migrations.RunSQL('''
            DELETE FROM your_app_name_employee WHERE email IS NULL OR date_joined IS NULL;
        '''),
    ]
