import React from 'react';
import { render, screen } from '@testing-library/react';
import Table from './Table';

test('renders table with data', () => {
  const data = [
    { name: 'John', age: 30 },
    { name: 'Jane', age: 25 }
  ];
  render(<Table data={data} />);
  expect(screen.getByText('John')).toBeInTheDocument();
  expect(screen.getByText('30')).toBeInTheDocument();
  expect(screen.getByText('Jane')).toBeInTheDocument();
  expect(screen.getByText('25')).toBeInTheDocument();
});
