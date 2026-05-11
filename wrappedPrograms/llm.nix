{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
  in {
    # bash script for practicing language with an llm
    packages.asktest = pkgs.writeShellApplication {
      name = "asktest";
      runtimeInputs = [self'.packages.ask];
      text = ''
        set -euo pipefail
        RESET="\033[0m"
        BOLD="\033[1m"
        DIM="\033[2m"
        CYAN="\033[36m"
        YELLOW="\033[33m"
        GREEN="\033[32m"
        BLUE="\033[34m"
        MAGENTA="\033[35m"
        WHITE="\033[97m"
        ORANGE="\033[38;5;214m"
        if [[ $# -gt 0 ]]; then
          TOPIC="$1"
        else
          printf '%b' "''${CYAN}Topic: ''${RESET}"
          read -r TOPIC
        fi
        echo -e "''${DIM}Generating cards for topic: ''${WHITE}$TOPIC''${RESET}''${DIM}...''${RESET}"
        echo ""
        CARDS=$(ask "You are a language learning question answer generator.
        Generate memory cards on this topic: $TOPIC
        If the topic specifies a number of cards, use that number. Otherwise generate 10 cards.
        Questions related to language learning must include natural modern spoken language, not academic.
        Use exactly this format for every card, with a blank line between cards:
        Q: <question>
        A: <answer>
        T: <a short hint to help answer — for translation questions: the English meaning of the question; For conversation/improvisation: meaning of difficult words in the question, words that may be useful when answering;>
        F: <extensive tips, mnemonics, extra context, common mistakes, usage examples — everything that helps this stick>
        Extensive tips must be in English
        Questions must be EXACTLY one of these three types, cycling in order: Translation, Conversation, Improvisation, Translation, Conversation, Improvisation...
        Do NOT invent other question formats.

        Translation: <A single vocabulary word or short phrase in target language (with plural forms and grammatical gender if noun, conjugation if verb) — translate to English>

        Conversation: <Natural conversation question directed AT the learner as a customer/visitor>

        Improvisation: <(IN ENGLISH) How do you say <something> in target language - respond in target languge>

        Output only the cards, no intro or extra text.")
        mapfile -t QUESTIONS < <(echo "$CARDS" | grep '^Q:' | sed 's/^Q: //')
        mapfile -t ANSWERS   < <(echo "$CARDS" | grep '^A:' | sed 's/^A: //')
        mapfile -t TIPS      < <(echo "$CARDS" | grep '^T:' | sed 's/^T: //')
        mapfile -t FACTS     < <(echo "$CARDS" | grep '^F:' | sed 's/^F: //')
        TOTAL=''${#QUESTIONS[@]}
        echo -e "''${GREEN}Got $TOTAL cards.''${RESET} ''${DIM}Press Enter after each answer. Press Enter with no answer to reveal a hint.''${RESET}"
        echo -e "''${DIM}----------------------------------------''${RESET}"
        RESULTS=""
        for i in "''${!QUESTIONS[@]}"; do
            NUM=$((i + 1))
            echo ""
            echo -e "''${DIM}Card ''${BOLD}''${WHITE}$NUM / $TOTAL''${RESET}"
            echo -e "''${CYAN}''${BOLD}Q: ''${QUESTIONS[$i]}''${RESET}"
            printf '%b' "''${YELLOW}Your answer: ''${RESET}"
            read -r USER_ANSWER
            if [[ -z "$USER_ANSWER" ]]; then
                echo ""
                echo -e "  ''${ORANGE}''${BOLD}💭 ''${TIPS[$i]}''${RESET}"
                echo ""
                printf '%b' "''${YELLOW}Your answer: ''${RESET}"
                read -r USER_ANSWER
            fi
            echo ""
            echo -e "  ''${GREEN}''${BOLD}✓ ''${ANSWERS[$i]}''${RESET}"
            echo -e "  ''${MAGENTA}💡 ''${FACTS[$i]}''${RESET}"
            echo ""
            printf '%b' "''${DIM}Press Enter for next card...''${RESET}"
            read -r
            RESULTS+="Card $NUM
        Q: ''${QUESTIONS[$i]}
        Correct answer: ''${ANSWERS[$i]}
        Your answer: $USER_ANSWER
        Hint used: $([ -z "$USER_ANSWER" ] && echo yes || echo no)
        "
        done
        echo ""
        echo -e "''${DIM}All done! Sending your answers for grading...''${RESET}"
        echo -e "''${DIM}----------------------------------------''${RESET}"
        RATING=$(ask "I practiced flashcards on the topic \"$TOPIC\". Grade my answers below.
        For each card, note:
        - Whether my answer is correct, partially correct, or wrong
        - A brief comment if needed
        - If a hint was used, factor that into the score slightly
        At the end, give:
        - A total score (X / $TOTAL)
        - 2-3 sentences of overall feedback
        Here are my answers:
        $RESULTS")
        echo ""
        echo -e "''${BLUE}''${RATING}''${RESET}"
      '';
    };

    packages.ask = pkgs.writeShellApplication {
      name = "ask";
      text = ''
        API_KEY=$(cat /persist/openrouterapi)
        PROMPT="''${1:-$(cat)}"

        curl -s https://openrouter.ai/api/v1/chat/completions \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -H "HTTP-Referer: https://local" \
          -H "X-Title: cli" \
          -d "{\"model\":\"google/gemini-3.1-flash-lite\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}]}" \
        | ${lib.getExe pkgs.jq} -r '.choices[0].message.content'
      '';
    };
  };
}
