import React from 'react';
import { render, screen } from '@testing-library/react';
import Chart from './Chart';

test('renders chart with data', () => {
  const data = [10, 20, 30, 40];
  render(<Chart data={data} />);
  // Note: This is a mock test. Actual implementation would require rendering the chart and checking if it's rendered correctly.
});
