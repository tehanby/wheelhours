import axios from 'axios';

const API_URL = 'http://localhost:3001/api'; // Adjust this URL according to your backend server

export const fetchData = async () => {
  try {
    const response = await axios.get(`${API_URL}/data`);
    return response.data;
  } catch (error) {
    console.error('Error fetching data:', error);
    throw error;
  }
};
