import React from 'react';
import Breadcrumb from './breadcrumb';

const App = () => {
  const breadcrumbItems = [
    { label: 'Home', isLink: true, href: '/' },
    { label: 'Services' },
    { label: 'Web Development' }
  ];

  return (
    <div className="App">
      <h1>Breadcrumb Example</h1>
      <Breadcrumb items={breadcrumbItems} />
    </div>
  );
};

export default App;
