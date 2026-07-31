import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import Input from './Input';

test('updates value on input change', () => {
  const handleChange = jest.fn();
  render(<Input onChange={handleChange} />);
  fireEvent.change(screen.getByRole('textbox'), { target: { value: 'test' } });
  expect(handleChange).toHaveBeenCalledWith(expect.any(Object));
});
