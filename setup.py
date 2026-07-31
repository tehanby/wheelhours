from setuptools import setup, find_packages

setup(
    name='WheelHours',
    version='0.1',
    packages=find_packages(),
    install_requires=[
        'flask',  # Example dependency
        # Add other dependencies here
    ],
    entry_points={
        'console_scripts': [
            'whlhours=wheelhours.app:run',
        ],
    },
)
