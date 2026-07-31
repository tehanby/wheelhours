from django.core.management.base import BaseCommand
from .models import Task

class Command(BaseCommand):
    help = 'Populates the database with sample tasks'

    def handle(self, *args, **options):
        Task.objects.create(title='Task 1', description='Description of task 1')
        Task.objects.create(title='Task 2', description='Description of task 2')
        self.stdout.write(self.style.SUCCESS('Successfully populated tasks'))
