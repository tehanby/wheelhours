import unittest

def run_tests():
    suite = unittest.TestLoader().discover('relative/path/to/tests')
    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(suite)

if __name__ == '__main__':
    run_tests()
