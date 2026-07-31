import os

def gather_user_feedback():
    """Gather user feedback on their journey through the application."""
    feedback_file = os.path.join("C:\\AI_Workspace\\wheelhours", "user_feedback.txt")
    
    if not os.path.exists(feedback_file):
        print(f"Feedback file {feedback_file} does not exist. Please create it.")
        return
    
    with open(feedback_file, 'r') as file:
        feedback = file.readlines()
    
    return [line.strip() for line in feedback]

def analyze_user_feedback(feedback):
    """Analyze the collected user feedback to identify pain points and opportunities."""
    pain_points = []
    opportunities = []

    for item in feedback:
        if "pain point" in item.lower():
            pain_points.append(item)
        elif "opportunity" in item.lower() or "improvement" in item.lower():
            opportunities.append(item)

    return pain_points, opportunities

def main():
    user_feedback = gather_user_feedback()
    if user_feedback:
        pain_points, opportunities = analyze_user_feedback(user_feedback)
        print("Pain Points:")
        for point in pain_points:
            print(f"- {point}")
        
        print("\nOpportunities for Improvement:")
        for opportunity in opportunities:
            print(f"- {opportunity}")

if __name__ == "__main__":
    main()
