import React from 'react';
import { useAccessibility } from '@wheelhours/accessibility';

const UserProfile = ({ user }) => {
  const accessibilityProps = useAccessibility({
    role: 'main',
    tabIndex: 0,
    onFocus: () => console.log('User profile focused'),
  });

  return (
    <div {...accessibilityProps}>
      <h1>User Profile</h1>
      <p>Username: {user.username}</p>
      <p>Email: {user.email}</p>
    </div>
  );
};

export default UserProfile;
