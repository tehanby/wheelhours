from .models import User, Course, user_course_association
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine

engine = create_engine('sqlite:///learning_paths.db')
Session = sessionmaker(bind=engine)
session = Session()

def fetch_user_progress(user_id):
    user = session.query(User).filter_by(id=user_id).first()
    if user:
        progress_data = []
        for course in user.progress:
            progress = {
                'course_title': course.title,
                'total_hours': course.total_hours,
                'completed_hours': sum(1 for _ in session.query(user_course_association.c.course_id).filter_by(course_id=course.id, user_id=user_id))
            }
            progress_data.append(progress)
        return progress_data
    else:
        return None

def update_user_progress(user_id, course_id):
    user = session.query(User).filter_by(id=user_id).first()
    if user and course_id not in [course.id for course in user.progress]:
        new_course = Course.query.filter_by(id=course_id).first()
        if new_course:
            user.progress.append(new_course)
            session.commit()
            return True
    return False
