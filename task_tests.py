import unittest
from task_manager import TaskManager

class TestTaskManager(unittest.TestCase):
    def setUp(self):
        self.task_manager = TaskManager()

    def test_add_task(self):
        task_id = "123"
        task = {'id': task_id, 'signed_off': False}
        self.task_manager.add_task(task)
        self.assertIn(task, self.task_manager.get_tasks())

    def test_remove_task(self):
        task_id = "456"
        task = {'id': task_id, 'signed_off': False}
        self.task_manager.add_task(task)
        self.task_manager.remove_task(task_id)
        self.assertNotIn(task, self.task_manager.get_tasks())

    def test_sign_off_task(self):
        task_id = "789"
        supervisor_name = "John Doe"
        task = {'id': task_id, 'signed_off': False}
        self.task_manager.add_task(task)
        result = self.task_manager.sign_off_task(task_id, supervisor_name)
        self.assertTrue(result)
        self.assertIn('signed_off_by', task)
        self.assertEqual(task['signed_off_by'], supervisor_name)

if __name__ == "__main__":
    unittest.main()
