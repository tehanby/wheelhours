from kivy.lang import Builder

KV = '''
#:import MDRaisedButton kivymd.uix.button.MDRaisedButton
#:import MDTextField kivymd.uix.textfield.MDTextField

Screen:
    BoxLayout:
        orientation: 'vertical'
        padding: dp(24)
        spacing: dp(16)

        MDTextField:
            id: input_field
            hint_text: 'Enter text'

        MDRaisedButton:
            id: submit_button
            text: 'Submit'
            on_release: root.on_submit()

    Label:
        id: output_label
'''

class DesignRevampScreen(MDScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self KV = Builder.load_string(KV)

    def on_submit(self):
        text = self.ids.input_field.text
        if text:
            self.ids.output_label.text = f'You entered: {text}'
