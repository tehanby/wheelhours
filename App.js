import React, { useState } from 'react';
import Breadcrumb from './components/Breadcrumb';

const App = () => {
    const [paths, setPaths] = useState(['Home', 'Services', 'Consulting']);

    return (
        <div className="App">
            <Breadcrumb paths={paths} />
            {/* Rest of your app content */}
        </div>
    );
};

export default App;
