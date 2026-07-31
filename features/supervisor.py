class Supervisor:
    def __init__(self, name, email):
        self.name = name
        self.email = email

    @staticmethod
    def validate_supervisor(supervisor_data):
        if not supervisor_data.get('name') or not supervisor_data.get('email'):
            raise ValueError("Supervisor data must include 'name' and 'email'")
        return supervisor_data

    @classmethod
    def create_supervisor(cls, supervisor_data):
        validated_data = cls.validate_supervisor(supervisor_data)
        return cls(validated_data['name'], validated_data['email'])
