# Finalize Database Schema Changes Migration

from django.db import migrations, models

class Migration(migrations.Migration):

    dependencies = [
        ('your_app_name', '0009_auto_20230401_1500'),
    ]

    operations = [
        # Add any final schema changes here
        migrations.AlterField(
            model_name='employee',
            name='email',
            field=models.EmailField(max_length=254, unique=True),
        ),
        migrations.CreateModel(
            name='PolicyCompliance',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('compliance_check', models.CharField(max_length=100)),
                ('is_compliant', models.BooleanField(default=False)),
                ('employee', models.ForeignKey(on_delete=models.CASCADE, to='your_app_name.Employee')),
            ],
        ),
    ]
