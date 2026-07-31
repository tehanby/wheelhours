from django.urls import path
from .views import approve_task, reject_task

urlpatterns = [
    path('tasks/approve/<int:task_id>/', approve_task, name='approve_task'),
    path('tasks/reject/<int:task_id>/', reject_task, name='reject_task'),
]
