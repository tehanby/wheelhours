# Routes for onboarding experience

from flask import Blueprint, render_template, request, redirect, url_for
from .handlers import get_onboarding_steps, mark_step_complete, check_step_completed

bp = Blueprint('onboarding', __name__)

@bp.route('/onboarding')
def onboarding():
    steps = get_onboarding_steps()
    current_step_id = int(request.args.get('step', 1))
    
    if not check_step_completed(current_step_id):
        step = next((s for s in steps if s['step_id'] == current_step_id), None)
        
        if step:
            if request.method == 'POST' and request.form.get('mark_complete'):
                mark_step_complete(current_step_id)
                return redirect(url_for('.onboarding', step=current_step_id + 1))
            
            return render_template('onboarding/step.html', step=step, current_step_id=current_step_id, steps_count=len(steps))
    
    return redirect(url_for('dashboard.index'))

@bp.route('/onboarding/complete')
def onboarding_complete():
    session['completed_steps'] = []
    return redirect(url_for('dashboard.index'))
