from kivy.app import App
from kivy.uix.screenmanager import ScreenManager, Screen

class DesignRevampApp(App):
    def build(self):
        sm = ScreenManager()
        sm.add_widget(DesignRevampScreen(name='design_revamp'))
        return sm

if __name__ == '__main__':
    DesignRevampApp().run()
