import React from 'react';
import { render, screen } from '@testing-library/react';
import Tabs from './Tabs';

test('renders tabs and active tab content', () => {
  const tabs = [
    { label: 'Tab 1', content: 'Content of Tab 1' },
    { label: 'Tab 2', content: 'Content of Tab 2' }
  ];
  render(<Tabs tabs={tabs} />);
  expect(screen.getByText('Tab 1')).toBeInTheDocument();
  expect(screen.getByText('Content of Tab 1')).toBeInTheDocument();
});
