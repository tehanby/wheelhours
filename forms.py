from django import forms
from .models import Supervisor

class SupervisorForm(forms.ModelForm):
    class Meta:
        model = Supervisor
        fields = ['name', 'email']

    def clean_email(self):
        email = self.cleaned_data.get('email')
        if Supervisor.objects.filter(email=email).exists():
            raise forms.ValidationError("This email is already registered.")
        return email
