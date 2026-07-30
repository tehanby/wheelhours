# Import necessary libraries
from sqlalchemy import create_engine, select, and_
from sqlalchemy.orm import sessionmaker
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class QueryOptimizer:
    def __init__(self, db_url):
        self.engine = create_engine(db_url)
        self.Session = sessionmaker(bind=self.engine)

    def fetch_drive_logs(self, page_number, page_size):
        session = self.Session()
        offset = (page_number - 1) * page_size

        # Create a select statement with pagination
        stmt = select(DriveLog).order_by(DriveLog.id).offset(offset).limit(page_size)
        
        try:
            result = session.execute(stmt)
            drive_logs = result.scalars().all()
            return drive_logs
        except Exception as e:
            logger.error(f"Error fetching drive logs: {e}")
        finally:
            session.close()

# Assuming DriveLog is a SQLAlchemy model representing the DriveLogs table
class DriveLog(Base):
    __tablename__ = 'drive_logs'
    id = Column(Integer, primary_key=True)
    log_entry = Column(String)
    timestamp = Column(DateTime)

# Example usage
if __name__ == "__main__":
    optimizer = QueryOptimizer('sqlite:///example.db')
    logs = optimizer.fetch_drive_logs(1, 50)  # Fetching the first page of 50 drive logs
    for log in logs:
        print(log.log_entry)
