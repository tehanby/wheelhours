import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import ManageSupervisors from './Pages/ManageSupervisors';
import ManageSupervisorsVehicles from './Pages/ManageSupervisorsVehicles';

const App = () => {
  return (
    <Router>
      <Routes>
        <Route path="/manage-supervisors" element={<ManageSupervisors />} />
        <Route path="/manage-supervisors/vehicles" element={<ManageSupervisorsVehicles />} />
        {/* Add more routes for other forms */}
      </Routes>
    </Router>
  );
};

export default App;
