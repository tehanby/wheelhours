import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import Button from './Button';

test('calls onClick handler on click', () => {
  const handleClick = jest.fn();
  render(<Button onClick={handleClick}>Click me</Button>);
  fireEvent.click(screen.getByText('Click me'));
  expect(handleClick).toHaveBeenCalledTimes(1);
});
