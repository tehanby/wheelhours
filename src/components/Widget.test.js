import React from 'react';
import { render, screen } from '@testing-library/react';
import Widget from './Widget';

test('renders widget with title and content', () => {
  render(<Widget title="Title" content="Content" />);
  expect(screen.getByText('Title')).toBeInTheDocument();
  expect(screen.getByText('Content')).toBeInTheDocument();
});
