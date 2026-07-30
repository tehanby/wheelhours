import React from 'react';
import { useFormik } from 'formik';
import * as Yup from 'yup';
import { AnimatePresence, motion } from 'framer-motion';

const validationSchema = Yup.object({
  licensePlate: Yup.string().required('License plate is required'),
  make: Yup.string().required('Make is required'),
  model: Yup.string().required('Model is required'),
  year: Yup.number().integer().min(1900).max(new Date().getFullYear()).required('Year is required'),
});

const VehicleForm = ({ onSubmit, initialValues }) => {
  const formik = useFormik({
    initialValues,
    validationSchema,
    onSubmit,
  });

  return (
    <AnimatePresence>
      <motion.form
        onSubmit={formik.handleSubmit}
        variants={{
          hidden: { opacity: 0, scale: 0.9 },
          visible: { opacity: 1, scale: 1 },
        }}
        initial="hidden"
        animate="visible"
        exit="hidden"
      >
        <div>
          <label htmlFor="licensePlate">License Plate</label>
          <input
            id="licensePlate"
            name="licensePlate"
            type="text"
            value={formik.values.licensePlate}
            onChange={formik.handleChange}
            onBlur={formik.handleBlur}
          />
          {formik.touched.licensePlate && formik.errors.licensePlate ? (
            <div>{formik.errors.licensePlate}</div>
          ) : null}
        </div>
        {/* Add similar fields for make, model, year */}
        <button type="submit">Submit</button>
      </motion.form>
    </AnimatePresence>
  );
};

export default VehicleForm;
