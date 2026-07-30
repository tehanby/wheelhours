import React from 'react';
import { Button } from 'antd';
import { saveAs } from 'file-saver';

class ExportView extends React.Component {
    handleExport = async () => {
        try {
            const response = await fetch('/api/export-pdf');
            if (!response.ok) {
                throw new Error('Failed to generate PDF');
            }
            const blob = await response.blob();
            saveAs(blob, 'exported.pdf');
        } catch (error) {
            this.displayErrorMessage(error.message);
        }
    };

    displayErrorMessage = (message) => {
        // Implement logic to display error message to the user
        alert(message);
    };

    render() {
        return (
            <Button onClick={this.handleExport}>Export PDF</Button>
        );
    }
}

export default ExportView;
