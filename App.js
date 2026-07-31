import React from 'react';
import UserProfile from './components/UserProfile';

const App = () => {
  const user = {
    username: 'JohnDoe',
    email: 'john.doe@example.com',
  };

  return (
    <div>
      <UserProfile user={user} />
    </div>
  );
};

export default App;
