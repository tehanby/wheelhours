# Handlers for onboarding experience

from flask import render_template, session
from .config import ONBOARDING_STEPS

def get_onboarding_steps():
    """
    Returns the list of onboarding steps.
    """
    return ONBOARDING_STEPS

def mark_step_complete(step_id):
    """
    Marks a specific step as complete in the user's session.
    """
    if 'completed_steps' not in session:
        session['completed_steps'] = []
    if step_id not in session['completed_steps']:
        session['completed_steps'].append(step_id)

def check_step_completed(step_id):
    """
    Checks if a specific step has been completed by the user.
    """
    return step_id in session.get('completed_steps', [])
