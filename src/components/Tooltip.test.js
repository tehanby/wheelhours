import React from 'react';
import { render, fireEvent, screen } from '@testing-library/react';
import Tooltip from './Tooltip';

test('renders tooltip on hover', () => {
  render(<Tooltip text="This is a tooltip">Hover over me</Tooltip>);
  fireEvent.mouseEnter(screen.getByText('Hover over me'));
  expect(screen.getByText('This is a tooltip')).toBeInTheDocument();
});

test('hides tooltip on mouse leave', () => {
  render(<Tooltip text="This is a tooltip">Hover over me</Tooltip>);
  fireEvent.mouseEnter(screen.getByText('Hover over me'));
  fireEvent.mouseLeave(screen.getByText('Hover over me'));
  expect(screen.queryByText('This is a tooltip')).not.toBeInTheDocument();
});
