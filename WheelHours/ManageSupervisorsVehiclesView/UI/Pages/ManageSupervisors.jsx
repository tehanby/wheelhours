import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import ManageSupervisorsVehiclesView from '../Components/ManageSupervisorsVehiclesView';

const ManageSupervisors = () => {
  const navigate = useNavigate();

  const handleNavigation = (route) => {
    navigate(route);
  };

  return (
    <div>
      <h1>Manage Supervisors</h1>
      <button onClick={() => handleNavigation('/manage-supervisors/vehicles')}>Manage Vehicles</button>
      {/* Add similar buttons for other forms */}
      <ManageSupervisorsVehiclesView />
    </div>
  );
};

export default ManageSupervisors;
