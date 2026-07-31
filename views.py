from django.shortcuts import get_object_or_404, redirect
from .models import Task

def approve_task(request, task_id):
    task = get_object_or_404(Task, pk=task_id)
    if request.user.is_superuser:
        task.approve_task()
    return redirect('task_list')

def reject_task(request, task_id):
    task = get_object_or_404(Task, pk=task_id)
    if request.user.is_superuser:
        task.reject_task()
    return redirect('task_list')
