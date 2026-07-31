import React from 'react';
import { render, screen } from '@testing-library/react';
import Progress from './Progress';

test('renders progress bar with correct width', () => {
  render(<Progress value={50} />);
  const progressBar = screen.getByRole('progressbar');
  expect(progressBar).toHaveStyle(`width: ${50}%`);
});
