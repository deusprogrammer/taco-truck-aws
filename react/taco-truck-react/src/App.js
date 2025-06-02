import React, { useEffect } from 'react';
import { Amplify } from "aws-amplify";
import { signIn, signOut, confirmSignIn, signUp, getCurrentUser, fetchUserAttributes, fetchAuthSession } from "aws-amplify/auth";
import { get, post } from "aws-amplify/api";
import awsConfig from './config/aws-config';
import postTest from './testData';

import './App.css';

Amplify.configure(awsConfig);

const CHECK_LOGGED_IN = 'CHECK_LOGGED_IN';
const LOGIN_STEP = 'LOGIN";'
const SIGNUP_STEP = 'SIGN_UP';
const NEW_PASSWORD_STEP = 'CONFIRM_SIGN_IN_WITH_NEW_PASSWORD_REQUIRED';
const LOGGED_IN_STEP = 'LOGGED_IN';

const App = () => {
  const [authResults, setAuthResults] = React.useState(null);
  const [userAttributes, setUserAttributes] = React.useState(null);
  const [apiResponse, setApiResponse] = React.useState(null);
  const [nextStep, setNextStep] = React.useState(LOGIN_STEP);
  const [creds, setCreds] = React.useState({ username: '', password: '' });
  const [email, setEmail] = React.useState('');

  useEffect(() => {
    const checkCurrentUser = async () => {
      try {
        const { signInDetails } = await getCurrentUser();
        const attributes = await fetchUserAttributes();
        setUserAttributes(attributes);
        if (signInDetails) {
          setNextStep(LOGGED_IN_STEP);
          setAuthResults(JSON.stringify(signInDetails, null, 5));
        } else {
          setNextStep(LOGIN_STEP);
        }
      } catch (error) {
        console.warn("Error checking current user:", error);
        setNextStep(LOGIN_STEP);
      }
    };

    checkCurrentUser();
  }, []);
  
  const handleSignIn = async () => {
    const results = await signIn(creds);
    setAuthResults(JSON.stringify(results, null, 5));

    const { nextStep } = results;
    setNextStep(nextStep.signInStep);
  }

  const handleSignUp = async () => {
    const results = await signUp({ ...creds, email });
    setAuthResults(JSON.stringify(results, null, 5));

    const { nextStep } = results;
    setNextStep(nextStep.signInStep);
  }

  const handleSignOut = async () => {
    await signOut();
    setNextStep(LOGIN_STEP);
    setAuthResults(null);
  }

  const handleNewPassword = async () => {
    const confirmedResults = await confirmSignIn({ challengeResponse: creds.password });
    setNextStep(LOGGED_IN_STEP);
    setAuthResults(JSON.stringify(confirmedResults, null, 5));
  }

  const handleCreateTest = async () => {
    const { tokens } = await fetchAuthSession();
    const { response } = post({
      apiName: "taco-truck-api",
      path: "/panels",
      options: {
        body: postTest,
        headers: {
          Authorization: `${tokens.idToken.toString()}`
        }
      },
    });
    const { body } = await(response);
    setApiResponse(JSON.stringify(await body.json(), null, 5));
  }

  const handleGetTest = async () => {
    const { tokens } = await fetchAuthSession();
    const { response } = get({
      apiName: "taco-truck-api",
      path: "/panels",
      options: {
        headers: {
          Authorization: `${tokens.idToken.toString()}`
        }
      },
    });
    const { body } = await(response);
    setApiResponse(JSON.stringify(await body.json(), null, 5));
  }

  // const handleCreateTest = async () => {
  //   const sessionData = await fetchAuthSession();
  //   const response = await axios.post('https://api.example.com/panels', postTest, {
  //     headers: {
  //       'Content-Type': 'application/json',
  //       'Authorization': `Bearer ${sessionData.tokens.idToken}`
  //     }
  //   });
  //   setApiResponse(JSON.stringify(response, null, 5));
  // }

  let component = null;
  switch (nextStep) {
    case CHECK_LOGGED_IN:
      component = <div>Checking if you are logged in...</div>;
      break;
    case LOGIN_STEP:
      component = (
        <div>
          <input
            type="text"
            placeholder="Username"
            onChange={(e) => setCreds({ ...creds, username: e.target.value })} />
          <br />
          <input
            type="password"
            placeholder="Password"
            onChange={(e) => setCreds({ ...creds, password: e.target.value })} />
          <br />
          <button onClick={handleSignIn}>
            Sign In
          </button>
          <button onClick={() => setNextStep(SIGNUP_STEP)}>
            Sign Up
          </button>
        </div>
      );
      break;
    case SIGNUP_STEP:
      component = (
        <div>
          <input
            type="text"
            placeholder="Username"
            onChange={(e) => setCreds({ ...creds, username: e.target.value })} />
          <br />
          <input
            type="password"
            placeholder="Password"
            onChange={(e) => setCreds({ ...creds, password: e.target.value })} />
          <br />
          <input
            type="text"
            placeholder="Email"
            onChange={(e) => setEmail(e.target.value)} />
          <br />
          <button onClick={handleSignUp}>
            Sign Up
          </button>
          <button onClick={() => setNextStep(LOGIN_STEP)}>
            Sign In
          </button>
        </div>
      );
      break;
    case NEW_PASSWORD_STEP:
      component = (
        <div>
          <p>Please enter a new password:</p>
          <input
            type="password"
            placeholder="New Password"
            onChange={(e) => setCreds({ ...creds, password: e.target.value })} />
          <br />
          <button onClick={handleNewPassword}>
            Update Password
          </button>
        </div>
      );
      break;
    case LOGGED_IN_STEP:
      component = (
        <div>
          <h2>Welcome back!</h2>
          <p>You are now logged in.</p>
          <button onClick={handleCreateTest}>Test Create Panel Layout</button>
          <button onClick={handleGetTest}>Test Get Panel Layouts</button>
          <button onClick={handleSignOut}>
            Sign Out
          </button>
        </div>
      );
      break;
    default:
      console.log("Unknown step:", nextStep);
      component = <div>Unknown authentication step: {nextStep}</div>;
  }

  return (
    <div>
      <h1>Welcome to the Taco Truck!</h1>
      { component }
      {authResults && (
        <div>
          <h2>Authentication Results:</h2>
          <pre>{authResults}</pre>
          <pre>{apiResponse || JSON.stringify(userAttributes, null, 5)}</pre>
        </div>
      )}
    </div>
  );
}

export default App;
