from flask import Blueprint, render_template, url_for, flash, redirect, request
from flask_login import login_user, logout_user, current_user, login_required
from .models import User, Token
from .forms import LoginForm, RegistrationForm, ResetPasswordRequestForm, ResetPasswordForm

auth = Blueprint('auth', __name__)

@auth.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user is None or not user.check_password(form.password.data):
            flash('Invalid username or password')
            return redirect(url_for('auth.login'))
        login_user(user, remember=form.remember_me.data)
        return redirect(request.args.get('next') or url_for('main.index'))
    return render_template('login.html', title='Sign In', form=form)

@auth.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('main.index'))

@auth.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    form = RegistrationForm()
    if form.validate_on_submit():
        user = User(username=form.username.data, email=form.email.data)
        user.set_password(form.password.data)
        db.session.add(user)
        db.session.commit()
        flash('Congratulations, you are now a registered user!')
        return redirect(url_for('auth.login'))
    return render_template('register.html', title='Register', form=form)

@auth.route('/reset_password_request', methods=['GET', 'POST'])
def reset_password_request():
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    form = ResetPasswordRequestForm()
    if form.validate_on_submit():
        user = User.query.filter_by(email=form.email.data).first()
        if user:
            token = Token(token=str(uuid.uuid4()), user_id=user.id)
            db.session.add(token)
            db.session.commit()
            send_email(user.email, 'Reset Your Password',
                       'auth/email/reset_password',
                       user=user, token=token.token)
        flash('Check your email for the instructions to reset your password')
        return redirect(url_for('auth.login'))
    return render_template('reset_password_request.html', title='Reset Password', form=form)

@auth.route('/reset_password/<token>', methods=['GET', 'POST'])
def reset_password(token):
    if current_user.is_authenticated:
        return redirect(url_for('main.index'))
    user = User.query.join(Token, User.id == Token.user_id).filter_by(token=token).first()
    if not user:
        return flash('Invalid token')
    form = ResetPasswordForm()
    if form.validate_on_submit():
        user.set_password(form.password.data)
        db.session.delete(user.tokens[0])
        db.session.commit()
        flash('Your password has been reset.')
        return redirect(url_for('auth.login'))
    return render_template('reset_password.html', title='Reset Password', form=form)
