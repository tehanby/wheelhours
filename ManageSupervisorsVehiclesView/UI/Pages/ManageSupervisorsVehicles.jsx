import React, { useState } from 'react';
import VehicleForm from '../Components/VehicleForm';

const ManageSupervisorsVehicles = () => {
  const [vehicles, setVehicles] = useState([]);

  const handleAddVehicle = (vehicle) => {
    setVehicles([...vehicles, vehicle]);
  };

  return (
    <div>
      <h1>Manage Supervisors Vehicles</h1>
      <VehicleForm onSubmit={handleAddVehicle} initialValues={{ licensePlate: '', make: '', model: '', year: '' }} />
      {/* Add similar forms for other vehicles */}
      <ul>
        {vehicles.map((vehicle, index) => (
          <li key={index}>
            {vehicle.licensePlate} - {vehicle.make} {vehicle.model} ({vehicle.year})
          </li>
        ))}
      </ul>
    </div>
  );
};

export default ManageSupervisorsVehicles;
