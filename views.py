from django.shortcuts import render, redirect
from .forms import SupervisorForm

def add_supervisor(request):
    if request.method == 'POST':
        form = SupervisorForm(request.POST)
        if form.is_valid():
            supervisor = form.save(commit=False)
            supervisor.save()
            return redirect('supervisor_added_successfully')
    else:
        form = SupervisorForm()

    return render(request, 'add_supervisor.html', {'form': form})
