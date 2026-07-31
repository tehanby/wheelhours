from django.urls import path
from .views import add_supervisor

urlpatterns = [
    path('add-supervisor/', add_supervisor, name='add_supervisor'),
]
