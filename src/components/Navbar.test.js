import React from 'react';
import { render, screen } from '@testing-library/react';
import Navbar from './Navbar';

test('renders logo and navigation links', () => {
  render(<Navbar />);
  expect(screen.getByAltText(/logo/i)).toBeInTheDocument();
  expect(screen.getByText(/home/i)).toBeInTheDocument();
  expect(screen.getByText(/about/i)).toBeInTheDocument();
});
