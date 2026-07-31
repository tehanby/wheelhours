import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import Slider from './Slider';

test('updates value on slider change', () => {
  const handleChange = jest.fn();
  render(<Slider onChange={handleChange} />);
  fireEvent.change(screen.getByRole('slider'), { target: { value: '50' } });
  expect(handleChange).toHaveBeenCalledWith(expect.any(Object));
});
